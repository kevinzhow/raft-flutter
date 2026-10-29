import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'control_transition_paint_test.dart' show paintHost, pixel;

// raft-ui 0.7.0 `Button`: sizes 32 / 44 / 52, icon squares, sticker / outline / ghost / on-frame fills, the
// disabled and loading style (fill-muted, not opacity) and the keyboard focus ring.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

BoxDecoration _decoration(WidgetTester tester, Finder button) {
  final box = find
      .descendant(of: button, matching: find.byType(DecoratedBox))
      .first;
  return tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode sizes are 32 / 44 / 52 and the icon squares 32 / 44', (
      tester,
    ) async {
      Future<Size> sizeOf(
        RaftButtonSize size, {
        String label = 'Go',
        RaftGlyph? glyph,
      }) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftButton(
              key: const ValueKey('b'),
              label: label,
              glyph: glyph,
              uiSize: size,
              onPressed: () {},
            ),
          ),
        );
        return tester.getSize(find.byKey(const ValueKey('b')));
      }

      expect((await sizeOf(RaftButtonSize.md)).height, 32);
      expect((await sizeOf(RaftButtonSize.xs)).height, 32);
      expect((await sizeOf(RaftButtonSize.sm)).height, 32);
      expect((await sizeOf(RaftButtonSize.lg)).height, 44);
      expect((await sizeOf(RaftButtonSize.xl)).height, 52);
      expect(
        await sizeOf(RaftButtonSize.iconMd, label: '', glyph: RaftGlyph.search),
        const Size(32, 32),
      );
      expect(
        await sizeOf(RaftButtonSize.iconLg, label: '', glyph: RaftGlyph.search),
        const Size(44, 44),
      );
    });

    testWidgets('$mode on-frame is 36px and sits transparent on the frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          RaftButton(
            key: const ValueKey('b'),
            label: 'Acme',
            uiVariant: RaftButtonVariant.onFrame,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey('b'))).height, 36);
      expect(
        _decoration(tester, find.byKey(const ValueKey('b'))).color,
        const Color(0x00000000),
      );
    });

    testWidgets('$mode primary is a pink sticker with an ink border', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          RaftButton(
            key: const ValueKey('b'),
            label: 'Send',
            uiVariant: RaftButtonVariant.primary,
            onPressed: () {},
          ),
        ),
      );
      final d = _decoration(tester, find.byKey(const ValueKey('b')));
      expect(d.color, ui.attention);
      expect((d.border! as Border).top.color, ui.stickerInk);
      expect(d.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('$mode outline reads layer-card and line-strong', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          RaftButton(
            key: const ValueKey('b'),
            label: 'Assign',
            uiVariant: RaftButtonVariant.standard,
            onPressed: () {},
          ),
        ),
      );
      final d = _decoration(tester, find.byKey(const ValueKey('b')));
      expect(d.color, ui.layerCard);
      expect((d.border! as Border).top.color, ui.lineStrong);
    });

    testWidgets(
      '$mode disabled and busy use fill-muted and hairline, not opacity',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftButton(
              key: ValueKey('b'),
              label: 'Send',
              uiVariant: RaftButtonVariant.primary,
            ),
          ),
        );
        final d = _decoration(tester, find.byKey(const ValueKey('b')));
        expect(d.color, ui.fillMuted);
        // CSS keeps the hairline translucent; the box painter composites
        // it over the fill rather than baking the fill into the border.
        expect((d.border! as Border).top.color, ui.lineHairline);
        expect(
          find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
          findsNothing,
        );

        await tester.pumpWidget(
          _app(
            dark,
            RaftButton(
              key: const ValueKey('b'),
              label: 'Creating…',
              busy: true,
              onPressed: () {},
            ),
          ),
        );
        expect(find.byType(RaftPixelSpinner), findsOneWidget);
        expect(
          _decoration(tester, find.byKey(const ValueKey('b'))).color,
          ui.fillMuted,
        );
      },
    );

    testWidgets('$mode a disabled ghost icon button has no fill or border', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftButton(
            key: ValueKey('b'),
            label: '',
            glyph: RaftGlyph.search,
            uiVariant: RaftButtonVariant.ghost,
            uiSize: RaftButtonSize.iconMd,
          ),
        ),
      );
      final d = _decoration(tester, find.byKey(const ValueKey('b')));
      expect(d.color, const Color(0x00000000));
      expect((d.border! as Border).top.color, const Color(0x00000000));
    });

    testWidgets('$mode hover lays the pressed overlay over the resting fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        paintHost(
          raftTheme(dark: dark),
          RaftButton(
            key: const ValueKey('b'),
            label: 'Assign',
            uiVariant: RaftButtonVariant.standard,
            onPressed: () {},
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('b'))));
      await tester.pumpAndSettle();
      expect(
        await pixel(tester, const Offset(24, 24)),
        Color(Color.alphaBlend(ui.fillPressed, ui.layerCard).toARGB32()),
      );
    });
  }
}
