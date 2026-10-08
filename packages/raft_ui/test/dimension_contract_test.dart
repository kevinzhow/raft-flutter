import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  test(
    'sidebar directional geometry keeps overlay and in-flow headers distinct',
    () {
      final elegant = raftTheme(RaftFamily.elegant).extension<RaftTokens>()!;
      final desktop = RaftSidebarRecipe(
        elegant,
        viewportWidth: 1024,
        viewportHeight: 844,
      );
      expect(
        desktop.headerInset,
        const EdgeInsetsDirectional.only(start: 26, end: 18),
      );
      expect(
        desktop.contentInset(),
        const EdgeInsetsDirectional.fromSTEB(26, 56, 18, 12),
      );
      expect(desktop.contentInset(headerInFlow: true).top, 0);
      expect(desktop.contentInset(liveActivity: true).bottom, 68);
      final shortMobile = RaftSidebarRecipe(
        elegant,
        viewportWidth: 390,
        viewportHeight: 560,
      );
      expect(
        shortMobile.headerInset,
        const EdgeInsetsDirectional.symmetric(horizontal: 28),
      );
      expect(
        shortMobile.contentInset(),
        const EdgeInsetsDirectional.fromSTEB(28, 48, 28, 12),
      );
      expect(shortMobile.contentInset(liveActivity: true).bottom, 12);
      final brutal = RaftSidebarRecipe(
        raftTheme(RaftFamily.brutal).extension<RaftTokens>()!,
        viewportWidth: 1024,
        viewportHeight: 844,
      );
      expect(brutal.headerOverlaysContent, false);
      expect(brutal.headerInset.start, 20);
      expect(
        brutal.contentInset(),
        const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 12),
      );
      expect(brutal.contentInset(liveActivity: true).bottom, 52);
    },
  );
  test(
    'rail keeps source theme glyph and compact face dimensions separate',
    () {
      final brutal = RaftRailRecipe(
        raftTheme(RaftFamily.brutal).extension<RaftTokens>()!,
        viewportHeight: 560,
      );
      final elegant = RaftRailRecipe(
        raftTheme(RaftFamily.elegant).extension<RaftTokens>()!,
        viewportHeight: 560,
      );
      expect(brutal.glyphSize, 18);
      expect(brutal.itemSize, 36);
      expect(brutal.width, 50);
      expect(elegant.glyphSize, 16);
      expect(elegant.itemSize, 40);
      expect(elegant.width, 56);
    },
  );
  test('mounted product sidebar overrides library geometry and reserves actual mobile overlay', () {
    final t = raftTheme(RaftFamily.elegant).extension<RaftTokens>()!;
    final desktop = RaftSidebarRecipe(
      t,
      viewportWidth: 1024,
      viewportHeight: 844,
      variant: RaftSidebarVariant.mountedProduct,
    );
    expect(desktop.headerOverlaysContent, false);
    expect(
      desktop.headerInset,
      const EdgeInsetsDirectional.symmetric(horizontal: 20),
    );
    expect(
      desktop.contentInset(),
      const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 12),
    );
    expect(desktop.contentInset(headerInFlow: true), desktop.contentInset());
    final workspace = RaftSidebarRecipe(
      t,
      viewportWidth: 1024,
      viewportHeight: 844,
      variant: RaftSidebarVariant.mountedProduct,
      workspaceEnabled: true,
    );
    expect(workspace.headerHeight, 48);
    expect(workspace.headerInset.start, 16);
    final mobile = RaftSidebarRecipe(
      t,
      viewportWidth: 390,
      viewportHeight: 844,
      variant: RaftSidebarVariant.mountedProduct,
    );
    expect(mobile.headerInset.start, 16);
    expect(mobile.contentInset().bottom, 68);
    expect(
      mobile.contentInset(liveActivity: true, bottomInset: 24).bottom,
      140,
    );
    final brutal = RaftSidebarRecipe(
      raftTheme(RaftFamily.brutal).extension<RaftTokens>()!,
      viewportWidth: 390,
      viewportHeight: 844,
      variant: RaftSidebarVariant.mountedProduct,
    );
    expect(brutal.contentInset(liveActivity: true, bottomInset: 24).bottom, 12);
  });
  test(
    'sidebar uses the source body role across theme and responsive variants',
    () {
      for (final (family, dark, mobile, expected) in [
        (RaftFamily.elegant, false, true, const Color(0xfff8f8f7)),
        (RaftFamily.elegant, true, true, const Color(0xff0d0d0b)),
        (RaftFamily.elegant, true, false, const Color(0xff0d0d0b)),
        (RaftFamily.brutal, false, true, Colors.white),
        (RaftFamily.brutal, false, false, const Color(0xfffffaef)),
      ]) {
        final t = raftTheme(family, dark: dark).extension<RaftTokens>()!;
        for (final variant in RaftSidebarVariant.values) {
          final r = RaftSidebarRecipe(
            t,
            viewportWidth: mobile ? 390 : 1024,
            viewportHeight: 844,
            variant: variant,
          );
          expect(r.bodyBackground, expected);
        }
      }
    },
  );
  for (final family in RaftFamily.values) {
    testWidgets(
      '$family constrained segmented options wrap and retain keyboard order',
      (tester) async {
        var value = 'small';
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family),
            home: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.desktop,
                child: StatefulBuilder(
                  builder: (context, update) => Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 150,
                      child: RaftSegmentedControl(
                        label: 'Font size',
                        value: value,
                        visualHeight: 32,
                        style: RaftSegmentedStyle.buttons,
                        onChanged: (next) => update(() => value = next),
                        items: const [
                          RaftSegmentedOption(value: 'small', label: 'Small'),
                          RaftSegmentedOption(value: 'medium', label: 'Medium'),
                          RaftSegmentedOption(value: 'large', label: 'Large'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // segmentedControl items (RaftRecipeBox per item).
        final controls = find.byType(RaftRecipeBox);
        expect(controls, findsNWidgets(3));
        expect(
          tester.getTopLeft(controls.last).dy,
          greaterThan(tester.getTopLeft(controls.first).dy),
        );
        for (var index = 0; index < 3; index++) {
          expect(
            tester.getRect(controls.at(index)).right,
            lessThanOrEqualTo(150),
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(value, 'medium');
        await tester.tap(find.text('Large'));
        expect(value, 'large');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
