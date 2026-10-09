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
    for (final height in [915.0, 568.0]) {
      for (final density in RaftDensity.values) {
        testWidgets(
          '$family/$dark height$height $density source roles retain geometry and callbacks',
          (tester) async {
            var activations = 0;
            final selected = ValueNotifier(false);
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(412, height);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(family, dark: dark),
                home: Scaffold(
                  body: RaftDensityScope(
                    density: density,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 320,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: selected,
                          builder: (context, active, _) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (role, glyph, label) in [
                                (
                                  RaftNavItemRole.search,
                                  RaftGlyph.search,
                                  'Search',
                                ),
                                (
                                  RaftNavItemRole.activity,
                                  RaftGlyph.activity,
                                  'Activity',
                                ),
                                (
                                  RaftNavItemRole.saved,
                                  RaftGlyph.bookmark,
                                  'Saved',
                                ),
                              ])
                                RaftNavItem(
                                  key: ValueKey(role),
                                  role: role,
                                  label: label,
                                  glyph: glyph,
                                  viewportHeight: height,
                                  selected: active,
                                  count: role == RaftNavItemRole.saved
                                      ? 5
                                      : null,
                                  onTap: () => activations++,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            for (final role in [
              RaftNavItemRole.search,
              RaftNavItemRole.activity,
              RaftNavItemRole.saved,
            ]) {
              final nav = find.byKey(ValueKey(role));
              final control = find.descendant(
                of: nav,
                matching: find.byType(RaftControl),
              );
              final widget = tester.widget<RaftControl>(control);
              final recipe =
                  widget.recipe! as RaftMountedSidebarNavigationRecipe;
              final compact = height <= 600;
              final expected = family == RaftFamily.brutal
                  ? compact
                        ? 32.0
                        : 40.0
                  : role == RaftNavItemRole.saved
                  ? compact
                        ? 29.5
                        : 33.5
                  : compact
                  ? 30.0
                  : 38.0;
              expect(recipe.sourceHeight, expected);
              expect(widget.visualHeight, expected);
              // Sidebar.tsx row box on every density (no 48dp inflation).
              expect(tester.getSize(nav).height, expected + 4);
              expect(
                recipe.textStyle.fontFamily,
                family == RaftFamily.brutal
                    ? 'packages/raft_ui/HankenGrotesk'
                    : 'packages/raft_ui/Inter',
              );
              expect(recipe.textStyle.fontWeight, FontWeight.w500);
              expect(
                recipe.textStyle.fontSize,
                family == RaftFamily.elegant && role == RaftNavItemRole.saved
                    ? 13
                    : 14,
              );
              final glyph = tester.widget<RaftIcon>(
                find.descendant(of: nav, matching: find.byType(RaftIcon)),
              );
              expect(glyph.size, 14);
              expect(recipe.side().color, Colors.transparent);
              expect(recipe.shadows(), isEmpty);
            }
            final searchControl = find.descendant(
              of: find.byKey(const ValueKey(RaftNavItemRole.search)),
              matching: find.byType(RaftControl),
            );
            final gesture = await tester.startGesture(
              tester.getCenter(searchControl),
            );
            await tester.pump();
            expect(
              (tester.widget<RaftControl>(searchControl).recipe!
                      as RaftMountedSidebarNavigationRecipe)
                  .pointerPressed,
              isTrue,
            );
            expect(
              tester.widget<RaftControl>(searchControl).recipe!.side().color,
              isNot(Colors.transparent),
            );
            await gesture.cancel();
            await tester.pump();
            expect(
              tester.widget<RaftControl>(searchControl).recipe!.side().color,
              Colors.transparent,
            );
            expect(activations, 0);
            expect(find.text('5'), findsOneWidget);
            await tester.tap(
              find.byKey(const ValueKey(RaftNavItemRole.activity)),
            );
            await tester.pump();
            expect(activations, 1);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pump();
            expect(activations, 2);
            selected.value = true;
            await tester.pump();
            final active = tester.widget<RaftControl>(
              find.descendant(
                of: find.byKey(const ValueKey(RaftNavItemRole.activity)),
                matching: find.byType(RaftControl),
              ),
            );
            expect(active.recipe!.textStyle.fontWeight, FontWeight.w700);
            expect(active.recipe!.side().color, isNot(Colors.transparent));
            await tester.pumpWidget(const SizedBox());
            selected.dispose();
          },
        );
      }
    }
  }

  testWidgets(
    'generic callers stay generic; notification defaults and rail options share exact glyph sizing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftDensityScope(
              density: RaftDensity.desktop,
              child: Column(
                children: [
                  RaftNavItem(
                    label: 'Existing',
                    glyph: RaftGlyph.search,
                    onTap: () {},
                  ),
                  const RaftMobileNotificationButton(),
                  const RaftMobileNotificationButton(
                    visualSize: 40,
                    glyphSize: 18,
                  ),
                  const RaftIcon(RaftGlyph.wifiOff, size: 14),
                  const RaftIcon(RaftGlyph.hardDrive, size: 14),
                ],
              ),
            ),
          ),
        ),
      );
      final nav = tester.widget<RaftNavItem>(find.byType(RaftNavItem));
      expect(nav.role, RaftNavItemRole.generic);
      final controls = tester
          .widgetList<RaftControl>(find.byType(RaftControl))
          .toList();
      expect(controls[0].visualHeight, 32);
      expect(controls[0].recipe, isNull);
      expect(controls[1].visualHeight, 32);
      expect(controls[2].visualHeight, 40);
      final bells = tester
          .widgetList<RaftIcon>(find.byType(RaftIcon))
          .where((w) => w.glyph == RaftGlyph.bell)
          .toList();
      expect(bells.map((b) => b.size), [16, 18]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
