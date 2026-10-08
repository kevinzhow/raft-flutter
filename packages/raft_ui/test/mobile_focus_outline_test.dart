import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const navItems = [
  RaftMobileNavItem(
    id: 'home',
    label: 'Home',
    glyph: RaftGlyph.home,
    key: ValueKey('focus-tab-home'),
  ),
  RaftMobileNavItem(
    id: 'tasks',
    label: 'Tasks',
    glyph: RaftGlyph.squareCheck,
    key: ValueKey('focus-tab-tasks'),
  ),
  RaftMobileNavItem(
    id: 'members',
    label: 'Members',
    glyph: RaftGlyph.users,
    key: ValueKey('focus-tab-members'),
  ),
  RaftMobileNavItem(
    id: 'settings',
    label: 'Settings',
    glyph: RaftGlyph.settings,
    key: ValueKey('focus-tab-settings'),
  ),
];

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final density in RaftDensity.values) {
      testWidgets(
        'pointer selected shadow survives; keyboard separate outline recipe is2px+2px: $family/$dark/$density',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            var selected = 'home';
            var activations = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(family, dark: dark),
                home: Scaffold(
                  body: RaftDensityScope(
                    density: density,
                    child: StatefulBuilder(
                      builder: (context, setState) => Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: 412,
                          child: RaftMobileNav(
                            items: navItems,
                            selectedId: selected,
                            viewportHeight: 915,
                            bottomInset: 0,
                            onSelected: (id) => setState(() {
                              selected = id;
                              activations++;
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final tasks = find.byKey(const ValueKey('focus-tab-tasks'));
            final gesture = await tester.startGesture(
              tester.getCenter(tasks),
              kind: density == RaftDensity.desktop
                  ? PointerDeviceKind.mouse
                  : PointerDeviceKind.touch,
            );
            await gesture.up();
            await tester.pump(const Duration(milliseconds: 200));
            expect(selected, 'tasks');
            expect(activations, 1);
            final control = tester.widget<RaftControl>(tasks);
            expect(control.recipe!.focusOutlineWidth, 2);
            expect(control.recipe!.focusOutlineOffset, 2);
            final detector = tester.widget<FocusableActionDetector>(
              find.descendant(
                of: tasks,
                matching: find.byType(FocusableActionDetector),
              ),
            );
            expect(
              detector.focusNode!.hasFocus,
              isTrue,
            ); // Focus retained, paint is modality-specific.
            final surface = find.descendant(
              of: tasks,
              matching: find.byType(AnimatedContainer),
            );
            final pointerPaint =
                tester.widget<AnimatedContainer>(surface).decoration!
                    as BoxDecoration;
            final tokens = RaftTokens.of(tester.element(tasks));
            expect(
              pointerPaint.boxShadow,
              control.recipe!.shadows(focused: false),
            );
            expect(
              control.recipe!.shadows(focused: true),
              control.recipe!.shadows(focused: false),
            );
            final paintCount = find
                .descendant(of: tasks, matching: find.byType(CustomPaint))
                .evaluate()
                .length;
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pump(const Duration(milliseconds: 200));
            expect(activations, 2);
            expect(detector.focusNode!.hasFocus, isTrue);
            final keyboardPaint =
                tester.widget<AnimatedContainer>(surface).decoration!
                    as BoxDecoration;
            expect(
              keyboardPaint.boxShadow,
              pointerPaint.boxShadow,
            ); // Selected ring/shadow never replaced by outline.
            expect(
              find
                  .descendant(of: tasks, matching: find.byType(CustomPaint))
                  .evaluate()
                  .length,
              paintCount + 1,
            );
            if (!tokens.brutal) {
              final capsule = tester.getSize(
                find.byKey(const ValueKey('mobile-nav-source-capsule')),
              );
              expect(capsule, const Size(208, 52)); // Source face geometry independent of transparent touch48 target.
            }
            await tester.tap(find.byKey(const ValueKey('focus-tab-home')));
            await tester.pump(const Duration(milliseconds: 200));
            expect(selected, 'home');
            expect(activations, 3);
            expect(detector.focusNode!.hasFocus, isFalse);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
