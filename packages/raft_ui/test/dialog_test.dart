import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'dialog parts and bounded scroll preserve callbacks ${theme.$1}/${theme.$2}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var confirmed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: Scaffold(
              body: Builder(
                builder: (context) => RaftButton(
                  label: 'Open',
                  onPressed: () => showRaftDialog<void>(
                    context: context,
                    builder: (context) => RaftDialog(
                      title: 'Review changes',
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 30; i++) Text('Entry $i'),
                        ],
                      ),
                      actions: [
                        RaftButton(
                          label: 'Confirm',
                          onPressed: () {
                            confirmed = true;
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('REVIEW CHANGES'), findsOneWidget);
        final box = tester.getRect(find.byType(RaftDialog));
        expect(
          box.width,
          390,
        ); // Root owns the viewport; content recipe is narrower.
        final content = find
            .descendant(
              of: find.byType(RaftDialog),
              matching: find.byType(RaftRecipeBox),
            )
            .first;
        expect(tester.getSize(content).width, 358);
        expect(tester.takeException(), isNull);
        final scroll = find.descendant(
          of: find.byType(RaftDialogBody),
          matching: find.byType(Scrollable),
        );
        await tester.drag(scroll, const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(confirmed, true);
        expect(find.byType(RaftDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Escape closes the owned dialog and restores trigger focus', (
    tester,
  ) async {
    final trigger = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              focusNode: trigger,
              onPressed: () => showRaftDialog<void>(
                context: context,
                builder: (_) => const RaftDialog(
                  title: 'Keyboard review',
                  content: Text('Body'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    trigger.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(RaftDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(RaftDialog), findsNothing);
    expect(trigger.hasFocus, true);
    await tester.pumpWidget(const SizedBox());
    trigger.dispose();
  });
  testWidgets('alert cancel returns false and a confirm returns true', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: Builder(
            builder: (context) => RaftButton(
              label: 'Open',
              onPressed: () async {
                result = await showRaftAlertDialog(
                  context: context,
                  title: 'Delete channel?',
                  description: 'This cannot be undone.',
                  destructive: true,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(RaftDialogClose), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(tester.takeException(), isNull);
  });
  for (final alert in [false, true]) {
    testWidgets('modal focus remains inside ${alert ? "alert" : "dialog"}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: Builder(
                builder: (context) => RaftButton(
                  label: 'Open',
                  onPressed: () => showRaftDialog<void>(
                    context: context,
                    builder: (_) => RaftDialog(
                      kind: alert
                          ? RaftDialogKind.alert
                          : RaftDialogKind.dialog,
                      title: 'Owned modal',
                      content: const Text('Body'),
                      actions: [RaftButton(label: 'Confirm', onPressed: () {})],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final route = ModalRoute.of(tester.element(find.byType(RaftDialog)));
        for (var i = 0; i < 8; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focusContext = FocusManager.instance.primaryFocus?.context;
          expect(focusContext, isNotNull);
          expect(
            ModalRoute.of(focusContext!),
            same(route),
            reason: 'Tab must cycle through this modal, never its hidden page.',
          );
        }
        final role = alert ? SemanticsRole.alertDialog : SemanticsRole.dialog;
        final roleNode = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.role == role,
        );
        expect(roleNode, findsOneWidget);
        expect(tester.getSemantics(roleNode).getSemanticsData().role, role);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      } finally {
        semantics.dispose();
      }
    });
  }
}
