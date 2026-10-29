import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'control_paint.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'dark=$dark floating navigation centers content in painted face',
      (tester) async {
        var selected = '';
        await tester.pumpWidget(
          MaterialApp(
            // This44px face/18px glyph contract belongs to the capsule.
            // Default docked geometry is covered by mobile_nav_contract_test.
            theme: raftTheme(
              pack: packForThemeId(elegantThemePackId),
              dark: dark,
            ),
            home: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.touch,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 390,
                    child: RaftMobileNav(
                      selectedId: 'chat',
                      onSelected: (id) => selected = id,
                      viewportHeight: 844,
                      bottomInset: 0,
                      items: const [
                        RaftMobileNavItem(
                          id: 'chat',
                          label: 'Home',
                          glyph: RaftGlyph.home,
                        ),
                        RaftMobileNavItem(
                          id: 'tasks',
                          label: 'Tasks',
                          glyph: RaftGlyph.squareCheck,
                        ),
                        RaftMobileNavItem(
                          id: 'members',
                          label: 'Members',
                          glyph: RaftGlyph.users,
                        ),
                        RaftMobileNavItem(
                          id: 'settings',
                          label: 'Settings',
                          glyph: RaftGlyph.settings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final controls = find.byType(RaftControl);
        expect(controls, findsNWidgets(4));
        for (var index = 0; index < 4; index++) {
          final control = controls.at(index);
          final face = controlFace(control);
          final glyph = find.descendant(
            of: control,
            matching: find.byType(RaftIcon),
          );
          final faceRect = tester.getRect(face);
          expect(tester.getCenter(glyph).dx, closeTo(faceRect.center.dx, .001));
          expect(tester.getSize(glyph), const Size(18, 18));
          expect(faceRect.size, const Size(44, 44));
          expect(tester.getSize(control), const Size(48, 48));
          expect(tester.getCenter(glyph).dy, closeTo(faceRect.center.dy, .001));
        }
        await tester.tap(controls.at(1));
        expect(selected, 'tasks');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: raftLookSkip(raftLookElegant),
    );
    testWidgets(
      'dark=$dark control centers intrinsic text row without changing padding',
      (tester) async {
        const contentKey = ValueKey('control-row');
        const naturalKey = ValueKey('natural-control');
        const labelKey = ValueKey('natural-label');
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.desktop,
                child: Column(
                  children: [
                    RaftControl(
                      visualWidth: 160,
                      visualHeight: 32,
                      onPressed: () {},
                      child: const Row(
                        key: contentKey,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftIcon(RaftGlyph.plus, size: 16),
                          SizedBox(width: 8),
                          Text('Create'),
                        ],
                      ),
                    ),
                    RaftControl(
                      key: naturalKey,
                      visualHeight: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shadow: false,
                      onPressed: () {},
                      child: const Text('Natural', key: labelKey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final face = controlFace(find.byType(RaftControl).first);
        expect(
          tester.getCenter(find.byKey(contentKey)).dx,
          closeTo(tester.getCenter(face).dx, .001),
        );
        final naturalFace = controlFace(find.byKey(naturalKey));
        final insets =
            tester.getSize(naturalFace).width -
            tester.getSize(find.byKey(labelKey)).width;
        expect(
          insets,
          closeTo(
            24 +
                controlDecoration(
                  tester,
                  find.byKey(naturalKey),
                ).border!.dimensions.horizontal,
            .001,
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
