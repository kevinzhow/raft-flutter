import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [(RaftFamily.brutal, false), (RaftFamily.elegant, false), (RaftFamily.elegant, true)]) {
    testWidgets('Menu items paint and activate with and without a separator $theme', (tester) async {
      var activations = 0;
      await tester.pumpWidget(MaterialApp(
        theme: raftTheme(theme.$1, dark: theme.$2),
        home: Scaffold(body: SizedBox(width: 300, child: Semantics(role: SemanticsRole.menu, child: Column(children: [
          RaftMenuButtonItem(label: 'Open', onPressed: () => activations++),
          RaftMenuButtonItem(label: 'Separated', topDivider: true, onPressed: () => activations++),
          const RaftMenuButtonItem(label: 'Disabled'),
        ])))),
      ));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(activations, 1);
      Focus.of(tester.element(find.text('Separated'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activations, 2);
      await tester.tap(find.text('Disabled'));
      await tester.pump();
      expect(activations, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
