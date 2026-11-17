import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'control_paint.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
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
