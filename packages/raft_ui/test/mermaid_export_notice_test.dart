import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Transient-notice audit: a failed diagram export says so, and the message
/// must not stay once a later export works.
void main() {
  testWidgets(
    '"Could not export diagram." ends when the next export succeeds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var fail = true;
      final exported = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftMermaidBlock(
              source: 'flowchart LR\n A[Draft] --> B[Review]',
              onExport: (extension, Uint8List bytes) async {
                if (fail) throw StateError('disk full');
                exported.add(extension);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> exportSource() async {
        await tester.tap(find.byTooltip('Download Mermaid Diagram'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Download Source'));
        await tester.pumpAndSettle();
      }

      await exportSource();
      expect(find.text('Could not export diagram.'), findsOneWidget);
      fail = false;
      await exportSource();
      expect(exported, ['mmd']);
      expect(find.text('Could not export diagram.'), findsNothing);
    },
  );
}
