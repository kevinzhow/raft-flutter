import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Web `RuntimeChoiceCombobox`: the field itself is the search input.
void main() {
  const items = [
    RaftComboboxItem(
      'connection:a',
      'DeepSeek · Team key',
      hint: 'connection:a',
      keywords: 'connection:a',
      group: 'Saved providers',
    ),
    RaftComboboxItem(
      'connection:old',
      'DeepSeek · Retired key',
      group: 'Saved providers',
      enabled: false,
    ),
    RaftComboboxItem(
      'deepseek',
      'DeepSeek',
      hint: 'deepseek',
      group: 'Direct setup',
    ),
    RaftComboboxItem('gpt-6', 'GPT 6 Sol', group: 'Direct setup'),
  ];

  for (final theme in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
  ])) {
    group('$theme', () {
      late List<String> chosen, custom;
      Future<void> pump(
        WidgetTester tester, {
        String value = '',
        bool allowCustom = true,
        bool enabled = true,
      }) async {
        chosen = [];
        custom = [];
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 320,
                    child: RaftAgentCombobox(
                      key: const ValueKey('combo'),
                      label: 'Provider',
                      items: items,
                      value: value,
                      placeholder: 'Select...',
                      enabled: enabled,
                      onSelected: chosen.add,
                      customLabel: allowCustom
                          ? (typed) => 'Use “$typed”'
                          : null,
                      onCustom: allowCustom ? custom.add : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      Finder input() => find.descendant(
        of: find.byKey(const ValueKey('combo')),
        matching: find.byType(TextField),
      );

      testWidgets(
        'closed it shows the chosen name; opening lists under the field',
        (tester) async {
          await pump(tester, value: 'deepseek');
          expect(
            tester.widget<TextField>(input()).controller!.text,
            'DeepSeek',
          );
          expect(find.text('Saved providers'), findsNothing);
          await tester.tap(input());
          await tester.pumpAndSettle();
          // The field is the search box: no header, no second input.
          expect(find.byType(TextField), findsOneWidget);
          expect(find.text('Search...'), findsNothing);
          expect(find.text('Saved providers'), findsOneWidget);
          expect(find.text('Direct setup'), findsOneWidget);
          // The chosen name stays readable as the placeholder.
          expect(tester.widget<TextField>(input()).controller!.text, '');
          expect(
            tester.widget<TextField>(input()).decoration!.hintText,
            'DeepSeek',
          );
        },
      );

      testWidgets('typing in the field filters word by word', (tester) async {
        await pump(tester);
        await tester.tap(input());
        await tester.pumpAndSettle();
        await tester.enterText(input(), 'sol gpt');
        await tester.pump();
        expect(find.text('GPT 6 Sol'), findsOneWidget);
        expect(find.text('DeepSeek · Team key'), findsNothing);
        await tester.enterText(input(), 'connection:a');
        await tester.pump();
        expect(find.text('DeepSeek · Team key'), findsOneWidget);
        expect(find.text('GPT 6 Sol'), findsNothing);
      });

      testWidgets(
        'choosing a row closes the list and reports it; disabled rows cannot be chosen',
        (tester) async {
          await pump(tester);
          await tester.tap(input());
          await tester.pumpAndSettle();
          await tester.tap(find.text('DeepSeek · Retired key'));
          await tester.pumpAndSettle();
          expect(chosen, isEmpty);
          expect(find.text('Direct setup'), findsOneWidget);
          await tester.tap(find.text('GPT 6 Sol'));
          await tester.pumpAndSettle();
          expect(chosen, ['gpt-6']);
          expect(find.text('Direct setup'), findsNothing);
        },
      );

      testWidgets('arrow keys, Enter and Escape work from the field', (
        tester,
      ) async {
        await pump(tester);
        await tester.tap(input());
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        // The second press skips the disabled row.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(chosen, ['deepseek']);
        await tester.tap(input());
        await tester.pumpAndSettle();
        expect(find.text('Direct setup'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Direct setup'), findsNothing);
      });

      testWidgets('typed text that matches nothing can be used as is', (
        tester,
      ) async {
        await pump(tester, value: 'deepseek');
        await tester.tap(input());
        await tester.pumpAndSettle();
        await tester.enterText(input(), 'my-model');
        await tester.pump();
        await tester.tap(find.text('Use “my-model”'));
        await tester.pumpAndSettle();
        expect(custom, ['my-model']);
        expect(chosen, isEmpty);
      });

      testWidgets('without custom values the typed text is never offered', (
        tester,
      ) async {
        await pump(tester, allowCustom: false);
        await tester.tap(input());
        await tester.pumpAndSettle();
        await tester.enterText(input(), 'zzz');
        await tester.pump();
        expect(find.textContaining('Use'), findsNothing);
        expect(find.text('No results'), findsOneWidget);
      });

      testWidgets(
        'a tap outside closes the list and restores the chosen name',
        (tester) async {
          await pump(tester, value: 'gpt-6');
          await tester.tap(input());
          await tester.pumpAndSettle();
          await tester.enterText(input(), 'abc');
          await tester.tapAt(const Offset(5, 500));
          await tester.pumpAndSettle();
          expect(find.text('Direct setup'), findsNothing);
          expect(
            tester.widget<TextField>(input()).controller!.text,
            'GPT 6 Sol',
          );
          expect(chosen, isEmpty);
          expect(custom, isEmpty);
        },
      );

      testWidgets('a disabled combobox does not open', (tester) async {
        await pump(tester, enabled: false);
        await tester.tap(input(), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('Saved providers'), findsNothing);
      });
    });
  }
}
