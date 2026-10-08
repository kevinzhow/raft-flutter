import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final family in RaftFamily.values) {
    testWidgets(
      '${family.name} composer retains draft on failure and clears only on success',
      (tester) async {
        var success = false;
        final sent = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family),
            home: Scaffold(
              body: Column(
                children: [
                  RaftComposer(
                    onSend: (text) async {
                      sent.add(text);
                      return success;
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), '你好 · 日本語');
        await tester.tap(find.byTooltip('Send message (Ctrl+Enter)'));
        await tester.pump();
        expect(sent, ['你好 · 日本語']);
        expect(find.text('你好 · 日本語'), findsOneWidget);
        success = true;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(sent, hasLength(2));
        expect(find.text('你好 · 日本語'), findsNothing);
      },
    );
  }
  testWidgets('typing the next draft while sending never loses that draft', (
    tester,
  ) async {
    final delivery = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(body: RaftComposer(onSend: (_) => delivery.future)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'First message');
    await tester.tap(find.byTooltip('Send message (Ctrl+Enter)'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
    await tester.enterText(find.byType(TextField), 'Next draft 日本語');
    delivery.complete(true);
    await tester.pump();
    expect(find.text('Next draft 日本語'), findsOneWidget);
  });
  testWidgets('navigation semantics expose selection and unread count', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant, dark: true),
        home: Scaffold(
          body: RaftNavItem(
            label: 'general',
            icon: Icons.tag,
            onTap: () {},
            selected: true,
            unread: 3,
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('general, 3 unread'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(RaftNavItem)),
      matchesSemantics(
        label: 'general, 3 unread',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
  testWidgets('accessible targets and text contrast for controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: RaftButton(label: 'Send', onPressed: () {}),
        ),
      ),
    );
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
  testWidgets('Ctrl+Enter does not submit an active IME composition', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftComposer(
            onSend: (text) async {
              sent.add(text);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '日本語',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('日本語'), findsOneWidget);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '日本語',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(sent, ['日本語']);
  });
  for (final theme in [
    raftTheme(RaftFamily.brutal),
    raftTheme(RaftFamily.elegant),
    raftTheme(RaftFamily.elegant, dark: true),
  ]) {
    testWidgets(
      'task statuses and reaction controls retain accessible targets ${theme.brightness} ${theme.extension<RaftTokens>()!.family}',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final status in raftTaskStatuses)
                      RaftTaskCard(
                        title: 'Task title',
                        number: '42',
                        status: status,
                        onTap: () {},
                        onStatus: (_) {},
                        statusOptions: raftTaskStatuses,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      },
    );
  }
  for (final theme in [
    raftTheme(RaftFamily.brutal),
    raftTheme(RaftFamily.elegant),
    raftTheme(RaftFamily.elegant, dark: true),
  ]) {
    testWidgets(
      'destructive high-contrast button target and contrast ${theme.brightness} ${theme.extension<RaftTokens>()!.family}',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(highContrast: true),
              child: Scaffold(
                body: RaftButton(
                  label: 'Delete',
                  destructive: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        try {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          handle.dispose();
        }
      },
    );
  }
}
