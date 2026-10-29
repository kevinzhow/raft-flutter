import 'dart:ui' show CheckedState;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'choice dialog $dark keeps typed selection and skips disabled rows',
      (tester) async {
        int? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Builder(
              builder: (context) => RaftButton(
                label: 'Open',
                onPressed: () async {
                  result = await showRaftDialog<int>(
                    context: context,
                    builder: (context) => RaftChoiceDialog<int>(
                      title: 'Choose workspace',
                      options: const [
                        RaftChoiceDialogOption(
                          value: 10,
                          label: 'First',
                          selected: true,
                        ),
                        RaftChoiceDialogOption(
                          value: 20,
                          label: 'Disabled',
                          enabled: false,
                        ),
                        RaftChoiceDialogOption(value: 30, label: 'Third'),
                      ],
                      onSelected: (value) => Navigator.pop(context, value),
                      onClose: () => Navigator.pop(context),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(RaftDialogSurface), findsOneWidget);
        expect(find.byType(SimpleDialog), findsNothing);
        expect(find.byType(RaftPopoverSurface), findsNothing);
        final semantics = tester.ensureSemantics();
        final first = find.byWidgetPredicate(
          (widget) =>
              widget is RaftInteractive && widget.semanticLabel == 'First',
        );
        expect(
          tester.getSemantics(first).flagsCollection.isChecked,
          CheckedState.isTrue,
        );
        expect(tester.getSize(first).height, 36);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(result, 30);
        expect(find.byType(RaftDialogSurface), findsNothing);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
  ]) {
    testWidgets(
      'choice dialog $platform large text grows and keyboard reveals both directions',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        int? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(3.1)),
              child: child!,
            ),
            home: Scaffold(
              body: RaftChoiceDialog<int>(
                title: 'Choose workspace',
                options: [
                  for (var index = 0; index < 20; index++)
                    RaftChoiceDialogOption(
                      value: index,
                      label: 'Workspace $index with a long descriptive name',
                    ),
                ],
                onSelected: (value) => result = value,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byWidgetPredicate(
          (widget) =>
              widget is RaftInteractive &&
              widget.semanticLabel ==
                  'Workspace 0 with a long descriptive name',
        );
        expect(tester.getSize(first).height, greaterThan(36));
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pumpAndSettle();
        final last = find.text('Workspace 19 with a long descriptive name');
        expect(last.hitTestable(), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(result, 19);
        for (var step = 0; step < 19; step++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
        }
        expect(
          find.text('Workspace 0 with a long descriptive name').hitTestable(),
          findsOneWidget,
          reason: 'ArrowUp must reveal rows above the current dialog viewport',
        );
        expect(result, 19, reason: 'focus movement does not select a value');
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pumpAndSettle();
        expect(
          find.text('Workspace 0 with a long descriptive name').hitTestable(),
          findsOneWidget,
          reason: 'Home must reveal the first row after End',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(result, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'choice dialog keyed options retain focused value across reorder and prepend',
    (tester) async {
      int? result;
      var order = <int>[10, 20, 30];
      late StateSetter changeOptions;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: StatefulBuilder(
              builder: (context, setState) {
                changeOptions = setState;
                return RaftChoiceDialog<int>(
                  title: 'Choose workspace',
                  options: [
                    for (final value in order)
                      RaftChoiceDialogOption(
                        key: ValueKey('choice-$value'),
                        value: value,
                        label: 'Workspace $value',
                        selected: value == 10,
                      ),
                  ],
                  onSelected: (value) => result = value,
                  onClose: () {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        changeOptions(() => order = [20, 30, 10]);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(
          result,
          20,
          reason: 'focus follows the option key, not its index',
        );
        result = null;
        changeOptions(() => order = [5, 20, 30, 10]);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(
          result,
          20,
          reason: 'prepending does not replace the focused value',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'choice dialog auxiliary action remains separate and accessible',
    (tester) async {
      var selected = 0, auxiliary = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: RaftChoiceDialog<String>(
            title: 'Switch Server',
            options: [
              RaftChoiceDialogOption(
                value: 'workspace',
                label: 'Workspace',
                onAuxiliary: () => auxiliary++,
                trailing: RaftButton(
                  key: const Key('independent-browser'),
                  label: 'Open in browser',
                  onPressed: () => auxiliary++,
                ),
              ),
            ],
            onSelected: (_) => selected++,
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byKey(const Key('independent-browser')))
            .flagsCollection
            .isButton,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('independent-browser')));
      expect(auxiliary, 1);
      expect(selected, 0);
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      final row = find.byWidgetPredicate(
        (widget) =>
            widget is RaftInteractive && widget.semanticLabel == 'Workspace',
      );
      await mouse.down(tester.getTopLeft(row) + const Offset(4, 4));
      await mouse.up();
      expect(auxiliary, 2);
      expect(selected, 0);
      await mouse.removePointer();
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
