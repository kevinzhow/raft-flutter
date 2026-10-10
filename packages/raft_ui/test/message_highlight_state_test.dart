import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  const code = 'flowchart LR\n  A[中文输入] --> B[日本語確認]';
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [411.0, 1280.0]) {
      testWidgets(
        '[K13a][K13c] highlight expiry preserves Mermaid source and selected text $family/$dark/$width',
        (tester) async {
          tester.view.physicalSize = Size(width, 915);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final highlighted = ValueNotifier(true);
          addTearDown(highlighted.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ValueListenableBuilder(
                    valueListenable: highlighted,
                    builder: (context, value, child) => RaftMessageTile(
                      author: 'Developer',
                      content:
                          'Native rich message\n\n**Markdown** and `code`\n\n```mermaid\n$code\n```',
                      body: const RaftMessageBody(
                        content:
                            'Native rich message\n\n**Markdown** and `code`\n\n```mermaid\n$code\n```',
                      ),
                      timestamp: '08:00 AM',
                      highlighted: value,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Show source'));
          await tester.pumpAndSettle();
          expect(find.text(code), findsOneWidget);
          final sourceRect = tester.getRect(find.byType(RaftMermaidBlock));
          final source = find.descendant(
            of: find.byType(RaftMermaidBlock),
            matching: find.byType(SelectableText),
          );
          expect(source, findsOneWidget);
          final selected = find.descendant(
            of: source,
            matching: find.byType(EditableText),
          );
          final point = tester.getTopLeft(source) + const Offset(20, 8);
          await tester.longPressAt(point);
          await tester.pumpAndSettle();
          final selection = tester
              .widget<EditableText>(selected)
              .controller
              .selection;
          expect(
            selection.isCollapsed,
            isFalse,
            reason: 'A real source text selection must exist before highlight expiry.',
          );
          highlighted.value = false;
          await tester.pumpAndSettle();
          expect(
            find.text(code),
            findsOneWidget,
            reason: 'Highlight paint expiry must not replace the selected code view.',
          );
          expect(tester.getRect(find.byType(RaftMermaidBlock)), sourceRect);
          expect(
            tester.widget<EditableText>(selected).controller.selection,
            selection,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
      testWidgets(
        '[K13b] highlight expiry preserves expanded long message $family/$dark/$width',
        (tester) async {
          tester.view.physicalSize = Size(width, 915);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final highlighted = ValueNotifier(true);
          addTearDown(highlighted.dispose);
          final content = List.generate(
            55,
            (i) => '中文 and 日本語 long paragraph $i',
          ).join('\n\n');
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ValueListenableBuilder(
                    valueListenable: highlighted,
                    builder: (context, value, child) => RaftMessageTile(
                      author: 'Developer',
                      content: content,
                      body: RaftMessageBody(content: content),
                      timestamp: '08:00 AM',
                      highlighted: value,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Show more'), findsOneWidget);
          final before = tester.getSize(find.byType(RaftCollapsible));
          await tester.tap(find.text('Show more'));
          await tester.pumpAndSettle();
          final expanded = tester.getSize(find.byType(RaftCollapsible));
          expect(expanded.height, greaterThan(before.height));
          expect(find.text('Collapse'), findsOneWidget);
          highlighted.value = false;
          await tester.pumpAndSettle();
          expect(find.text('Collapse'), findsOneWidget);
          expect(
            tester.getSize(find.byType(RaftCollapsible)),
            expanded,
            reason: 'Removing a paint highlight must retain user expansion.',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
