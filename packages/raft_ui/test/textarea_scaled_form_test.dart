import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    for (final scale in [1.0, 1.3, 2.0, 3.1]) {
      testWidgets(
        '${dark ? 'dark' : 'light'}/$scale textarea stays bounded in a scrolling form',
        (tester) async {
          final controller = TextEditingController();
          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: RaftTextScaling(child: child!),
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        RaftTextarea(
                          controller: controller,
                          rows: 2,
                          semanticLabel: 'Description',
                        ),
                        const Text('Following form field'),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byType(RaftTextarea)).height.isFinite,
              isTrue,
            );
            await tester.enterText(
              find.byType(TextField),
              'First line\nSecond line\nThird line',
            );
            await tester.pump();
            expect(controller.text, 'First line\nSecond line\nThird line');
            final input = tester.widget<TextField>(find.byType(TextField));
            expect(input.expands, isTrue);
            expect(input.maxLines, isNull);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            controller.dispose();
          }
        },
      );
    }
  }
}
