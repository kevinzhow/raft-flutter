import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'the download dialog shows a Raft progress bar that follows the value (dark=$dark)',
      (tester) async {
        final progress = ValueNotifier<double?>(null);
        addTearDown(progress.dispose);
        var canceled = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  attachmentDownloadProgressRoute(
                    context: context,
                    name: 'report.pdf',
                    progress: progress,
                    onCancel: () => canceled++,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.byType(RaftProgressBar), findsOneWidget);
        expect(
          tester.widget<RaftProgressBar>(find.byType(RaftProgressBar)).value,
          isNull,
        );
        progress.value = .5;
        await tester.pump();
        expect(
          tester.widget<RaftProgressBar>(find.byType(RaftProgressBar)).value,
          50,
        );
        expect(
          tester.getSize(find.byType(RaftProgressBar)).width,
          greaterThanOrEqualTo(240),
        );
        await tester.tap(find.text('Cancel'));
        expect(canceled, 1);
      },
    );
  }
}
