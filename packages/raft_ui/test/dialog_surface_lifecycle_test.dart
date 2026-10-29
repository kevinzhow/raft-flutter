import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'shared dialog paint preserves route dismissal and focus ($dark)',
      (tester) async {
        final launch = FocusNode();
        final field = FocusNode();
        final text = TextEditingController();
        var completions = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  focusNode: launch,
                  onPressed: () async {
                    await showGeneralDialog<void>(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: 'Dismiss fixture',
                      barrierColor: Colors.transparent,
                      transitionDuration: Duration.zero,
                      pageBuilder: (context, _, __) => RaftDialogBackdrop(
                        child: Center(
                          child: RaftDialogSurface(
                            child: SizedBox(
                              width: 280,
                              child: Padding(
                                padding: const EdgeInsets.all(RaftSpace.x4),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: TextField(
                                    key: const ValueKey('dialog-editor'),
                                    autofocus: true,
                                    focusNode: field,
                                    controller: text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    completions++;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        launch.requestFocus();
        await tester.pump();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(field.hasFocus, isTrue);
        await tester.enterText(
          find.byKey(const ValueKey('dialog-editor')),
          'kept',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(RaftDialogSurface), findsNothing);
        expect(completions, 1);
        expect(launch.hasFocus, isTrue);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(text.text, 'kept');
        expect(field.hasFocus, isTrue);
        // The paint-only scrim must let the route's own barrier receive this.
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(find.byType(RaftDialogSurface), findsNothing);
        expect(completions, 2);
        expect(launch.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        launch.dispose();
        field.dispose();
        text.dispose();
      },
    );
  }
}
