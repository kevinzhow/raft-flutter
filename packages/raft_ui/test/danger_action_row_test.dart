import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(double width, {bool dark = false, bool warning = false}) =>
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: RaftDangerActionRow(
              title: 'Delete server',
              description: 'Permanently remove this server and all its data. This cannot be undone.',
              actionLabel: 'Delete server',
              actionGlyph: warning ? null : RaftGlyph.trash2,
              warning: warning,
              actionKey: const Key('action'),
              onAction: () {},
            ),
          ),
        ),
      ),
    );

void main() {
  // DangerActionRow.tsx: the button sits at the row's end, and drops under
  // the text where the row is under 32rem of its own width.
  testWidgets('the action sits at the end of a wide row', (t) async {
    await t.pumpWidget(_host(700));
    final title = t.getRect(find.text('Delete server').first);
    final action = t.getRect(find.byKey(const Key('action')));
    expect(action.right, greaterThan(650));
    expect(action.center.dy, lessThan(title.bottom + 40));
    expect(action.left, greaterThan(title.right));
  });

  testWidgets('the action wraps under the text in a narrow row', (t) async {
    await t.pumpWidget(_host(360));
    final description = t.getRect(
      find.textContaining('Permanently remove').first,
    );
    final action = t.getRect(find.byKey(const Key('action')));
    expect(action.top, greaterThanOrEqualTo(description.bottom));
    expect(action.left, lessThan(60));
  });

  testWidgets('warning and danger tones render in both modes', (t) async {
    for (final dark in [false, true]) {
      for (final warning in [false, true]) {
        await t.pumpWidget(_host(700, dark: dark, warning: warning));
        expect(find.byKey(const Key('action')), findsOneWidget);
      }
    }
  });
}
