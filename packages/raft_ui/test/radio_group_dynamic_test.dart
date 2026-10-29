import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(
  List<String> values,
  ValueChanged<String> choose, {
  bool keyed = false,
}) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: RaftRadioGroup<String>(
      value: 'a',
      onChanged: choose,
      children: [
        for (final value in values)
          RaftRadioGroupItem<String>(
            key: keyed ? ValueKey(value) : null,
            value: value,
            child: Text(value),
          ),
      ],
    ),
  ),
);

void main() {
  testWidgets('arrow selection reads replaced item values', (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    final selected = <String>[];
    await t.pumpWidget(host(['a', 'b', 'c'], selected.add));
    await t.pumpWidget(host(['a', 'x', 'c'], selected.add));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(selected, ['x']);
  });

  testWidgets('arrow selection follows current keyed row order', (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    final selected = <String>[];
    await t.pumpWidget(host(['a', 'b', 'c'], selected.add, keyed: true));
    await t.pumpWidget(host(['a', 'c', 'b'], selected.add, keyed: true));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(selected, ['c']);
  });
}
