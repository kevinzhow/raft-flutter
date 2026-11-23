import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('collapsed Markdown mounts only visible blocks and can expand', (
    tester,
  ) async {
    final body = RaftMessageBody(
      content: [for (var index = 0; index < 30; index++) 'Paragraph $index.']
          .join('\n\n'),
      mountedMessage: true,
    );
    Widget host({required bool collapse}) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RaftCollapsible(enabled: collapse, child: body),
        ),
      ),
    );

    final last = find.text('Paragraph 29.', findRichText: true);
    final measure = find.byType(RaftContentMeasure);
    try {
      await tester.pumpWidget(host(collapse: false));
      final naturalHeight = tester.getSize(measure).height;
      expect(last, findsOneWidget);
      await tester.pumpWidget(host(collapse: true));
      expect(tester.getSize(measure).height, 320);
      expect(last, findsNothing);
      expect(find.text('Show More'), findsOneWidget);
      await tester.tap(find.text('Show More'));
      await tester.pumpAndSettle();
      expect(last, findsOneWidget);
      expect(tester.getSize(measure).height, naturalHeight);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }
  });
}
