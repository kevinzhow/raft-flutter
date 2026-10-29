import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_conversion_previews.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'phone conversion preview keeps recovery keyboard accessible in every theme',
    (t) async {
      t.view.physicalSize = const Size(320, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final semantics = t.ensureSemantics();
      try {
        for (final dark in [false, true]) {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(body: channelConversionPreview()),
            ),
          );
          await t.tap(find.text('failed'));
          await t.pump();
          expect(find.text('Conversion needs attention'), findsOneWidget);
          expect(
            t
                .widgetList<Semantics>(find.byType(Semantics))
                .any((s) => s.properties.liveRegion == true),
            isTrue,
          );
          t
              .widget<FocusableActionDetector>(
                find
                    .descendant(
                      of: find.widgetWithText(RaftButton, 'Retry Conversion'),
                      matching: find.byType(FocusableActionDetector),
                    )
                    .first,
              )
              .focusNode!
              .requestFocus();
          await t.pump();
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.pump();
          expect(find.text('Preparing conversion'), findsOneWidget);
          t
              .widget<FocusableActionDetector>(
                find
                    .descendant(
                      of: find.widgetWithText(RaftButton, 'Cancel Conversion'),
                      matching: find.byType(FocusableActionDetector),
                    )
                    .first,
              )
              .focusNode!
              .requestFocus();
          await t.pump();
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.pump();
          expect(find.text('Conversion canceled'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}
