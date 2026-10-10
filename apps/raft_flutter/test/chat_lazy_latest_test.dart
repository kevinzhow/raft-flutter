import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;
import 'support/p01_long_message_fixture.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('[P01] $family/$dark cold long-message latest window is lazy from first layout', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, _) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      final rows = contextRows('initial', count: 500);
      for (var i = 0; i < rows.length; i++) {
        rows[i]['content'] = p01LongMessage(i);
      }
      w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = rows.map((row) => row['id'] as String).toSet();
      await tester.pumpWidget(MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: Scaffold(body: RaftChatView(controller: w)),
      ));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(RaftMessageTile, skipOffstage: false).evaluate().length,
            lessThan(80), reason: 'Hidden staging is also bounded, frame $i');
      }
      expect(paintedMessage(tester, 'initial-499'), isNotNull);
      final dynamic state = tester.state(find.byType(RaftChatView));
      expect(state.viewport.offset, state.viewport.position.maxScrollExtent);
      expect(state.focusStaging, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
