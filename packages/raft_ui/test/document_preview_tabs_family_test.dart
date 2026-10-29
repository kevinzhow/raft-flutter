import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// The exact XLSX fixture used by the real Web/Flutter attachment route capture,
// not an invented control-board specimen. This guards canonical family wiring;
// paired real-screen pixel acceptance is a separate requirement.
Map<String, dynamic> _xlsx() {
  var root = Directory.current.absolute;
  while (true) {
    final file = File(
      '${root.path}/tool/parity-ext/fixtures/threadattachments.json',
    );
    if (file.existsSync()) {
      final fixture = jsonDecode(file.readAsStringSync()) as Map;
      return Map<String, dynamic>.from(
        fixture['documents']['xlsx']['preview'] as Map,
      );
    }
    if (root.parent.path == root.path)
      throw StateError('Missing shared XLSX fixture');
    root = root.parent;
  }
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'XLSX uses canonical Tabs and changes the actual sheet dark=$dark',
      (tester) async {
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(body: RaftDocumentPreview(data: _xlsx())),
          ),
        );
        expect(find.byType(RaftTabsList<int>), findsOneWidget);
        final selected = tester.widget<Text>(find.text('Summary'));
        expect(selected.style!.fontSize, 14);
        expect(selected.style!.fontWeight, FontWeight.w700);
        expect(find.text('Cases'), findsOneWidget);
        await tester.tap(find.text('Failing'));
        await tester.pump();
        expect(find.text('Cases'), findsNothing);
        expect(find.text('html.loading'), findsOneWidget);
        expect(find.text('88.0'), findsOneWidget);
      },
    );
  }
}
