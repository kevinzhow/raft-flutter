import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark message-select circle checkbox is 20px', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Center(
              child: RaftCheckbox(
                value: true,
                size: RaftCheckboxRecipeSize.lg,
                primary: true,
                circle: true,
                flatWhenChecked: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byType(RaftCheckbox)), const Size(20, 20));
      expect(t.takeException(), isNull);
    });
  }
}
