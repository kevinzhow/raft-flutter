import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.1 `Status`: a square presence pixel (size-1.5 / 2 / 9px / 11px, 2px radius, 1.5px ink border), the
// five presence lights per mode, the variant colours, and RaftStatusDot / RaftAttentionDot as the same pixel.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

RaftCssBox _box(WidgetTester tester) =>
    tester.widget<RaftCssBox>(find.byType(RaftCssBox).first);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode sizes are 6 / 8 / 9 / 11 squares, never circles', (
      tester,
    ) async {
      for (final (size, px, radius) in [
        (RaftStatusSize.xs, 6.0, 1.0),
        (RaftStatusSize.sm, 8.0, 2.0),
        (RaftStatusSize.md, 9.0, 2.0),
        (RaftStatusSize.lg, 11.0, 2.0),
      ]) {
        await tester.pumpWidget(_app(dark, RaftStatus(size: size)));
        expect(tester.getSize(find.byType(RaftStatus)), Size.square(px));
        final box = _box(tester);
        expect(box.radius, radius);
        expect(box.borderColor, ui.stickerInk);
      }
      // The default is the md pixel in the offline light.
      await tester.pumpWidget(_app(dark, const RaftStatus()));
      expect(tester.getSize(find.byType(RaftStatus)), const Size.square(9));
      expect(_box(tester).fill, ui.presence('offline'));
    });

    testWidgets('$mode presence lights use the --presence-* tokens', (
      tester,
    ) async {
      for (final p in RaftPresence.values) {
        await tester.pumpWidget(_app(dark, RaftStatus(presence: p)));
        expect(_box(tester).fill, ui.presence(p.name), reason: p.name);
      }
      expect(ui.presence('online'), isNot(ui.presence('busy')));
    });

    testWidgets('$mode variants read the brand and status colours', (
      tester,
    ) async {
      final expected = {
        RaftStatusVariant.primary: ui['brand-400'],
        RaftStatusVariant.accent: ui['attention-400'],
        RaftStatusVariant.information: ui['info'],
        RaftStatusVariant.success: ui['success'],
        RaftStatusVariant.warning: ui['warning'],
        RaftStatusVariant.danger: ui['danger'],
        RaftStatusVariant.default_: ui.presence('offline'),
      };
      for (final entry in expected.entries) {
        await tester.pumpWidget(_app(dark, RaftStatus(variant: entry.key)));
        expect(_box(tester).fill, entry.value, reason: entry.key.name);
      }
      // An explicit presence wins over the variant.
      await tester.pumpWidget(
        _app(
          dark,
          const RaftStatus(
            presence: RaftPresence.busy,
            variant: RaftStatusVariant.danger,
          ),
        ),
      );
      expect(_box(tester).fill, ui.presence('busy'));
    });

    testWidgets(
      '$mode a labelled status is an image, an unlabelled one is hidden',
      (tester) async {
        await tester.pumpWidget(
          _app(dark, const RaftStatus(semanticLabel: 'Online')),
        );
        expect(find.bySemanticsLabel('Online'), findsOneWidget);
        await tester.pumpWidget(_app(dark, const RaftStatus()));
        expect(find.byType(ExcludeSemantics), findsWidgets);
      },
    );

    testWidgets('$mode a state chip is a soft badge holding a Status', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftBadge(
            appearance: RaftBadgeRecipeAppearance.soft,
            leading: RaftStatus(presence: RaftPresence.busy),
            label: 'Working',
          ),
        ),
      );
      expect(tester.getSize(find.byType(RaftBadge)).height, 22);
      expect(find.byType(RaftStatus), findsOneWidget);
      // 6px padding, the 9px pixel, a 4px gap, then the label.
      expect(
        tester.getTopLeft(find.byType(RaftStatus)).dx -
            tester.getTopLeft(find.byType(RaftBadge)).dx,
        6,
      );
      expect(
        tester.getTopLeft(find.text('Working')).dx -
            tester.getTopRight(find.byType(RaftStatus)).dx,
        4,
      );
    });

    testWidgets(
      '$mode RaftStatusDot and RaftAttentionDot draw square presence pixels',
      (tester) async {
        await tester.pumpWidget(
          _app(dark, const RaftStatusDot(activity: RaftActivityTone.working)),
        );
        expect(
          tester.getSize(find.byType(RaftStatusDot)),
          const Size.square(9),
        );
        expect(_box(tester).fill, ui.presence('busy'));
        expect(_box(tester).radius, 2);

        await tester.pumpWidget(
          _app(
            dark,
            const RaftStatusDot(
              activity: RaftActivityTone.online,
              external: true,
              size: RaftStatusDotSize.lg,
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(RaftStatusDot)),
          const Size.square(11),
        );
        expect(_box(tester).fill, ui.presence('external'));

        await tester.pumpWidget(
          _app(dark, const RaftStatusDot(color: Color(0xff123456))),
        );
        expect(_box(tester).fill, const Color(0xff123456));

        await tester.pumpWidget(_app(dark, const RaftAttentionDot()));
        expect(_box(tester).fill, ui['attention-400']);
        expect(
          tester.getSize(find.byType(RaftAttentionDot)),
          const Size.square(9),
        );
        await tester.pumpWidget(
          _app(dark, const RaftAttentionDot(compact: true)),
        );
        expect(
          tester.getSize(find.byType(RaftAttentionDot)),
          const Size.square(6),
        );
        await tester.pumpWidget(
          _app(dark, const RaftAttentionDot(danger: true)),
        );
        expect(_box(tester).fill, ui.danger);
        await tester.pumpWidget(
          _app(dark, const RaftAttentionDot(warning: true)),
        );
        expect(_box(tester).fill, ui.warning);
      },
    );
  }
}
