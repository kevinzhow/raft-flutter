// Assertions against the painted control, independent of its animation widget.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Finder controlFace(Finder control) {
  final recipe = find.descendant(
    of: control,
    matching: find.byType(RaftRecipeBox),
  );
  if (recipe.evaluate().isNotEmpty) return recipe.first;
  return find
      .descendant(of: control, matching: find.byType(AnimatedContainer))
      .first;
}

BoxDecoration controlDecoration(WidgetTester tester, Finder control) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(of: control, matching: find.byType(DecoratedBox)),
      )
      .map(
        (box) => switch (box.decoration) {
          RaftLayeredDecoration d => d.base,
          BoxDecoration d => d,
          _ => null,
        },
      )
      .whereType<BoxDecoration>()
      .first;
}

Matrix4 controlTransform(WidgetTester tester, Finder control) {
  final transforms = tester.widgetList<Transform>(
    find.descendant(of: control, matching: find.byType(Transform)),
  );
  return transforms.firstOrNull?.transform ?? Matrix4.identity();
}
