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
        'highlight expiry preserves Mermaid source $family/$dark/$width',
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
          highlighted.value = false;
          await tester.pumpAndSettle();
          expect(
            find.text(code),
            findsOneWidget,
            reason: 'Highlight paint expiry must not replace the selected code view.',
          );
          expect(tester.getRect(find.byType(RaftMermaidBlock)), sourceRect);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
