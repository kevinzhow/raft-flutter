import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/row_extents.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows;
import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'mounted 600 projected messages reuse preparation through resize',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        api.routes['POST /channels/c1/read'] = (_) => {};
        w.messageDomain.ledger.switchServer('s1');
        final rows = [
          for (final row in contextRows('extent-projected', count: 600))
            {
              ...row,
              'content': List.filled(
                8,
                '中文 projected resize body ${row['id']}',
              ).join('\n'),
            },
        ];
        w.messageDomain.ledger.ingest(
          rows,
          expectedGeneration: w.messageDomain.ledger.generation,
        );
        w.messageDomain.visibleIds['c1'] = rows
            .map((row) => row['id'] as String)
            .toSet();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byType(RaftChatView));
        final window = state.adapter.messages as List;
        expect(window, hasLength(600));
        // The model's getter returns a new unmodifiable Map view each time.
        expect(
          identical(window.first.metadata, window.first.metadata),
          isFalse,
        );
        final prepared = raftRowExtents.debugContentPreparations;
        for (var step = 0; step < 12; step++) {
          tester.view.physicalSize = Size(800 + step * 30, 800);
          await tester.pumpAndSettle();
          expect(find.byType(RaftMessageTile), findsWidgets);
          expect(find.byType(RaftComposer), findsOneWidget);
          expect(identical(state.adapter.messages, window), isTrue);
          expect(tester.takeException(), isNull);
        }
        expect(
          raftRowExtents.debugContentPreparations,
          prepared,
          reason: 'Resizing must reuse the canonical row, despite model getter wrappers.',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );
}
