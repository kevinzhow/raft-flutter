import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'review and selection controls work at mobile width: $family/$dark',
      (tester) async {
        var selected = 1, copied = 0, saved = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: StatefulBuilder(
                  builder: (context, update) => RaftSelectionToolbar(
                    selected: selected,
                    total: 3,
                    onExit: () => update(() => selected = 0),
                    onSelectAll: () => update(() => selected = 3),
                    onCopyMarkdown: () => copied++,
                    onPreview: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: SizedBox(
                          height: 480,
                          child: RaftImageReview(
                            preview: const Text('Actual content'),
                            onClose: () => Navigator.pop(context),
                            onSave: () => saved++,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Select all loaded messages'));
        await tester.pump();
        expect(find.text('3 selected'), findsOneWidget);
        await tester.tap(find.text('Copy Markdown'));
        expect(copied, 1);
        await tester.tap(find.text('Preview image'));
        await tester.pumpAndSettle();
        expect(find.text('Actual content'), findsOneWidget);
        await tester.tap(find.text('Save image'));
        expect(saved, 1);
        await tester.tap(find.byTooltip('Close preview'));
        await tester.pumpAndSettle();
        expect(selected, 3);
        await tester.tap(find.byTooltip('Exit selection'));
        await tester.pump();
        expect(find.text('0 selected'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
