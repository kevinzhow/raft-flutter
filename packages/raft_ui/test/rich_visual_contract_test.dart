import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/diagram_theme.dart';

void main() {
  test('diagram semantic colors stay separate from Material seed colors', () {
    final light = raftMermaidTheme(dark: false);
    final dark = raftMermaidTheme(dark: true);
    expect(light.primaryColor.value, 0xfff5f0e8);
    expect(dark.primaryColor.value, 0xff202a38);
    expect(light.actorBkg, light.primaryColor);
    expect(dark.noteTextColor, dark.primaryTextColor);
    expect(light.fontSize, 16);
  });
  test('code language normalization preserves original authored text', () {
    const source = 'const count = 3; // hello';
    for (final language in ['TS', 'language-typescript', 'unknown', 'txt']) {
      final span = raftCodeSpan(
        source,
        language,
        const TextStyle(),
        dark: false,
      );
      expect(span.toPlainText(), source);
    }
    final large = List.filled(501, 'const n = 1;').join('\n');
    expect(
      raftCodeSpan(large, 'ts', const TextStyle(), dark: true).toPlainText(),
      large,
    );
  });
  testWidgets('code copy receives authored source and updates feedback', (
    tester,
  ) async {
    String? copied;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftMessageBody(
            content: '```ts\nconst n = 3;\n```',
            onCopyCode: (value) async => copied = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pumpAndSettle();
    expect(copied, 'const n = 3;');
    expect(find.byTooltip('Copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('diagram exports actual rendered PNG and discards byte lease', (
    tester,
  ) async {
    Uint8List? leased, copied;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: RaftMermaidBlock(
            source: 'flowchart LR\n A[Draft] --> B[Ship]',
            onExport: (extension, bytes) async {
              leased = bytes;
              copied = Uint8List.fromList(bytes);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Download Mermaid diagram').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.widgetWithText(PopupMenuItem<String>, 'Download PNG'),
            )
            .enabled,
        isTrue,
      );
      await tester.tap(find.text('Download PNG'));
      await tester.pumpAndSettle();
      final deadline = Stopwatch()..start();
      while (copied == null && deadline.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(
        copied,
        isNotNull,
        reason: 'Actual rendered PNG export must complete.',
      );
    });
    await tester.pumpAndSettle();
    expect(copied!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(leased!.every((value) => value == 0), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('diagram zoom and source remain bounded at mobile width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant, dark: true),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: RaftMermaidBlock(
              source: 'sequenceDiagram\n Alice->>Bob: Review',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('mermaid-toolbar'))).width,
      lessThan(360),
    );
    expect(find.byTooltip('Expand diagram'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Expand diagram')).width,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byTooltip('Show source'));
    await tester.pumpAndSettle();
    expect(find.text('sequenceDiagram\n Alice->>Bob: Review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
