import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final density in RaftDensity.values) {
    for (final enabled in [true, false]) {
      for (final tooltip in [null, 'Continue']) {
        testWidgets(
          '$density interaction role and bounds ($enabled, $tooltip)',
          (t) async {
            final handle = t.ensureSemantics();
            var clicks = 0;
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(),
                home: Scaffold(
                  body: RaftDensityScope(
                    density: density,
                    child: ListView(
                      children: [
                        Column(
                          children: [
                            const Text('Read this card first'),
                            RaftInteractive(
                              onPressed: enabled ? () => clicks++ : null,
                              tooltip: tooltip,
                              builder: (_, _) => const SizedBox(
                                width: 120,
                                height: 32,
                                child: Text('Continue'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(
              t
                  .getSemantics(find.text('Read this card first'))
                  .getSemanticsData()
                  .flagsCollection
                  .isButton,
              isFalse,
            );
            final control = find.bySemanticsLabel('Continue');
            expect(control, findsOneWidget);
            expect(
              t
                  .getSemantics(control)
                  .getSemanticsData()
                  .flagsCollection
                  .isButton,
              isTrue,
            );
            expect(
              t.getSemantics(control).rect.size,
              Size(120, density == RaftDensity.touch ? 48 : 32),
            );
            await t.tap(find.text('Continue'));
            expect(clicks, enabled ? 1 : 0);
            await t.pumpWidget(const SizedBox());
            handle.dispose();
          },
        );
      }
    }
  }
}
