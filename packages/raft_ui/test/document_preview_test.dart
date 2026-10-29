import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('narrow sheet selector remains usable', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(
                  child: RaftDocumentPreview(
                    data: {
                      'kind': 'xlsx',
                      'sheets': [
                        {
                          'name': '日本語',
                          'headers': ['Key', 'Value'],
                          'rows': [
                            ['first', 'one'],
                          ],
                          'rowCount': 1,
                          'columnCount': 2,
                        },
                        {
                          'name': '中文',
                          'headers': ['Key'],
                          'rows': [
                            ['second'],
                          ],
                          'rowCount': 1,
                          'columnCount': 1,
                        },
                      ],
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('first'), findsOneWidget);
      await tester.tap(find.text('中文'));
      await tester.pump();
      expect(find.text('second'), findsOneWidget);
      expect(find.bySemanticsLabel('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('unsupported empty table is safe', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RaftDocumentPreview(
            data: {'kind': 'csv', 'headers': [], 'rows': []},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
