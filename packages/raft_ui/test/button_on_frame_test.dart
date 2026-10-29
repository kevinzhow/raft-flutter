import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'control_paint.dart';

void main() {
  for (final dark in [false, true]) {
    for (final (platform, size) in [
      (TargetPlatform.linux, const Size(390, 844)),
      (TargetPlatform.android, const Size(856, 944)),
      (TargetPlatform.android, const Size(944, 856)),
    ]) {
      testWidgets(
        'on-frame source geometry and loading $dark/$platform/$size',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          var calls = 0;
          late StateSetter update;
          var busy = false;
          final semantics = t.ensureSemantics();
          try {
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark).copyWith(platform: platform),
                home: Scaffold(
                  body: Center(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        update = setState;
                        return RaftIconButton(
                          glyph: RaftGlyph.arrowLeft,
                          tooltip: 'Back',
                          uiVariant: RaftButtonVariant.onFrame,
                          busy: busy,
                          onPressed: () => calls++,
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            final action = find.byType(RaftIconButton);
            final face = controlFace(action);
            expect(t.getSize(face), const Size.square(36));
            expect(t.widget<RaftIcon>(find.byType(RaftIcon)).size, 20);
            await t.tap(action);
            expect(calls, 1);
            update(() => busy = true);
            await t.pump();
            expect(t.getSize(face), const Size.square(36));
            expect(find.bySemanticsLabel('Back'), findsOneWidget);
            await t.tap(action);
            expect(calls, 1);
            update(() => busy = false);
            await t.pumpAndSettle();
            await t.tap(action);
            expect(calls, 2);
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
