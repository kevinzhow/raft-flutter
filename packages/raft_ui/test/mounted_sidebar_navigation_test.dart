import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'generic callers stay generic; notification defaults and rail options share exact glyph sizing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
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
      final notificationButtons = find.byType(RaftMobileNotificationButton);
      expect(tester.getSize(notificationButtons.at(0)), const Size.square(32));
      expect(tester.getSize(notificationButtons.at(1)), const Size.square(40));
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
