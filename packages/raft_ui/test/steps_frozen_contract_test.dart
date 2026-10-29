// Bounded frozen contracts, not Frozen pixel/whole-suite acceptance.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (id, dark) in raftThemeMatrix(
    [
      (elegantThemePackId, false),
      (elegantThemePackId, true),
      (brutalThemePackId, false),
    ],
    look: (v) => raftLookOf(v.$1),
    dark: (v) => v.$2,
  )) {
    for (final width in [390.0, 900.0]) {
      testWidgets('Frozen Steps $id dark=$dark width=$width', (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id), dark: dark),
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, 844)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RaftSteps(
                    current: 1,
                    steps: const [
                      RaftStep(title: 'Connect'),
                      RaftStep(title: 'Channels'),
                      RaftStep(title: 'Health'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final marker = find.byType(RaftCssBox);
        expect(marker, findsNWidgets(3));
        // Frozen paint resolves the selected pack, never the default Raft map.
        final ui = RaftTokens.theme(pack: packForThemeId(id), dark: dark).ui;
        expect(t.widgetList<RaftCssBox>(marker).map((w) => w.fill), [
          ui.foreground,
          ui.brand,
          ui.layerCard,
        ]);
        expect(t.widgetList<RaftCssBox>(marker).map((w) => w.borderColor), [
          ui.foreground,
          ui.stickerInk,
          ui.lineSeam,
        ]);
        for (final e in marker.evaluate())
          expect(
            t.getSize(find.byElementPredicate((x) => x == e)),
            const Size(20, 20),
          );
        expect(find.byType(RaftRecipeBox), findsNothing);
        expect(find.text('1'), findsNothing);
        expect(find.text('2'), findsOneWidget);
        if (width < 640)
          expect(
            t.getTopLeft(find.text('Connect')).dy,
            greaterThan(t.getTopLeft(marker.first).dy + 20),
          );
        else
          expect(
            t.getTopLeft(find.text('Connect')).dy,
            t.getTopLeft(find.text('Health')).dy,
          );
        expect(t.takeException(), isNull);
      });
    }
  }
}
