import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _reason =
    'This model is not installed on this computer, so it cannot be picked here.';

Widget _panel({required bool wrap}) => MaterialApp(
  theme: raftTheme(dark: false),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 220,
        child: RaftComboboxPanel.items(
          label: 'Models',
          items: [
            const RaftComboboxItem('a', 'GPT-5'),
            RaftComboboxItem(
              'b',
              'GPT-4',
              group: 'Not available on this computer',
              description: _reason,
              enabled: false,
              wrapDescription: wrap,
            ),
          ],
          onSelected: (_) {},
          onDismiss: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a description ends in an ellipsis unless the row opts in', (
    tester,
  ) async {
    await tester.pumpWidget(_panel(wrap: false));
    final plain = tester.widget<Text>(find.text(_reason));
    expect(plain.maxLines, 1);
    expect(plain.overflow, TextOverflow.ellipsis);
    final plainHeight = tester.getSize(find.text(_reason)).height;

    await tester.pumpWidget(_panel(wrap: true));
    final wrapped = tester.widget<Text>(find.text(_reason));
    expect(wrapped.maxLines, isNull);
    expect(wrapped.overflow, isNot(TextOverflow.ellipsis));
    // The whole reason is laid out: more than one line, nothing cut.
    expect(tester.getSize(find.text(_reason)).height, greaterThan(plainHeight));
    // A disabled row still cannot be chosen.
    await tester.tap(find.text('GPT-4'), warnIfMissed: false);
    expect(tester.takeException(), isNull);
  });
}
