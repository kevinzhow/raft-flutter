// Web StableField `belowDescription` (`pb-4 empty:hidden`): a notice after the
// message row. Empty leaves no box and no gap; shown, 16 stay below it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<double> height(WidgetTester t, {Widget? below}) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: RaftStableField(
                key: const ValueKey('f'),
                label: 'Runtime',
                belowDescription: below,
                child: const SizedBox(height: 36),
              ),
            ),
          ),
        ),
      ),
    );
    return t.getSize(find.byKey(const ValueKey('f'))).height;
  }

  testWidgets('no notice, or one that renders nothing: the field is as it '
      'was', (t) async {
    final plain = await height(t);
    expect(await height(t, below: const SizedBox.shrink()), plain);
  });

  testWidgets('a shown notice adds its height and the 16 below it', (t) async {
    final plain = await height(t);
    final shown = await height(t, below: const SizedBox(height: 40));
    expect(shown - plain, greaterThanOrEqualTo(56));
    expect(shown - plain, lessThan(56 + 12));
  });
}
