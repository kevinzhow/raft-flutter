import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} message-select circle checkbox is 20px',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftCheckbox(
                  value: true,
                  shape: RaftCheckboxShape.circle,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(t.getSize(find.byType(RaftCheckbox)), const Size(20, 20));
        expect(t.takeException(), isNull);
      },
    );
  }
}
