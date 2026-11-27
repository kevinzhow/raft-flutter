import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_migration_panel.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'MigrationProgressPanel compares the failed and stopped attempts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: false),
          home: Scaffold(
            body: MigrationProgressPanel(
              migration: const {
                'state': 'failed',
                'migrationRef': 'MV-123',
                'retryOfMigrationId': 'previous',
                'retryComparison': {
                  'previousFailure': {'entries': 24},
                  'packed': {'files': 12, 'bytes': 2147483648, 'final': false},
                },
              },
              machines: const [],
              now: DateTime.utc(2026, 11, 28),
              formatTimestamp: (value) => value,
            ),
          ),
        ),
      );
      expect(find.text('Failed attempt'), findsOneWidget);
      expect(find.text('24 files'), findsOneWidget);
      expect(find.text('This attempt'), findsOneWidget);
      expect(find.text('12 files, 2 GiB when it stopped'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Migration ID')).dy,
        greaterThan(tester.getTopLeft(find.text('This attempt')).dy),
      );
      final semantics = tester.ensureSemantics();
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      try {
        await tester.tap(find.bySemanticsLabel('Copy migration ID MV-123'));
        await tester.pump();
        expect(
          calls
              .where((call) => call.method == 'Clipboard.setData')
              .single
              .arguments,
          {'text': 'MV-123'},
        );
      } finally {
        semantics.dispose();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
