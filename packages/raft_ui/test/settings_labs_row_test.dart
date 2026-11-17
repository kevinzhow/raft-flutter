import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _reason = 'Paused, draft, and retired Labs are read-only here.';

Widget _section() => const RaftServerLabsSection(
  status: RaftServerLabsStatus.ready,
  masterEnabled: true,
  canSetMaster: true,
  labs: [
    RaftServerLab(
      key: 'refs',
      name: 'Refs',
      description: 'Composer refs.\nSecond line makes the row taller.',
      checked: false,
      editable: false,
      disabledReason: _reason,
    ),
  ],
);

void main() {
  // ServerLabRow.tsx:38 (v1.24): the row is `items-center`, so the switch sits
  // at the vertical middle of a multi-line row, not at its top.
  testWidgets('Labs: a lab switch is centred on its row', (t) async {
    await t.pumpWidget(_host(_section()));
    final row = t.getRect(find.byKey(const ValueKey('server-lab-refs')));
    final sw = t.getRect(find.byType(RaftSwitch).last);
    expect(sw.center.dy, closeTo(row.center.dy, 1));
  });

  // ServerLabRow.tsx:51-63: a disabled lab shows its reason as a tooltip on
  // the switch (the reason is also printed under the row).
  testWidgets('Labs: the disabled switch carries the reason as a tooltip', (
    t,
  ) async {
    await t.pumpWidget(_host(_section()));
    final tip = find.ancestor(
      of: find.byType(RaftSwitch).last,
      matching: find.byType(RaftTooltip),
    );
    expect(tip, findsOneWidget);
    expect(t.widget<RaftTooltip>(tip).message, _reason);
    expect(t.widget<RaftTooltip>(tip).enabled, isTrue);
  });

  testWidgets('Labs: an editable switch has no tooltip', (t) async {
    await t.pumpWidget(
      _host(
        const RaftServerLabsSection(
          status: RaftServerLabsStatus.ready,
          masterEnabled: true,
          canSetMaster: true,
          labs: [
            RaftServerLab(
              key: 'refs',
              name: 'Refs',
              description: 'Composer refs.',
              checked: false,
              editable: true,
            ),
          ],
        ),
      ),
    );
    final tip = find.ancestor(
      of: find.byType(RaftSwitch).last,
      matching: find.byType(RaftTooltip),
    );
    expect(t.widget<RaftTooltip>(tip).enabled, isFalse);
  });
}
