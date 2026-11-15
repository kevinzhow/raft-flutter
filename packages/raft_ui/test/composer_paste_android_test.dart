import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Android: a copied file is a content URI, not text, so the selection
// toolbar's own Paste is missing. The composer offers it when the host says
// the clipboard carries attachments.
void main() {
  for (final available in [false, true]) {
    for (final hasStrings in [false, true]) {
      testWidgets(
        'Android toolbar offers Paste for attachments: '
        'attachments=$available strings=$hasStrings',
        variant: TargetPlatformVariant.only(TargetPlatform.android),
        (tester) async {
          final availability = ValueNotifier<bool>(available);
          addTearDown(availability.dispose);
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async => switch (call.method) {
              'Clipboard.hasStrings' => {'value': hasStrings},
              'Clipboard.getData' => hasStrings ? {'text': 'words'} : null,
              _ => null,
            },
          );
          var taken = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: RaftComposer(
                    onSend: (_) async => true,
                    pasteAttachmentsAvailable: availability,
                    onPasteAttachments: () async {
                      taken++;
                      return available;
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.longPress(find.byType(TextField));
          await tester.pumpAndSettle();
          expect(
            find.text('Paste'),
            available || hasStrings ? findsOneWidget : findsNothing,
          );
          if (!available && !hasStrings) return;

          await tester.tap(find.text('Paste'));
          await tester.pumpAndSettle();
          expect(taken, 1);
          // Attachments taken: no text. Otherwise the text paste runs.
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            available || !hasStrings ? isEmpty : 'words',
          );
          expect(find.text('Paste'), findsNothing);
        },
      );
    }
  }
}
