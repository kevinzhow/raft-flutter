import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final theme in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    testWidgets(
      'Combobox filters, selects by keyboard and rejects disabled interaction $theme',
      (tester) async {
        final selected = <String>[];
        var enabled = true, dismissed = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 220,
                  child: StatefulBuilder(
                    builder: (context, set) {
                      update = set;
                      return RaftComboboxPanel(
                        label: 'Channels',
                        glyph: RaftGlyph.hash,
                        options: const {
                          'design': '#design',
                          'general': '#general',
                        },
                        enabled: enabled,
                        onSelected: selected.add,
                        onDismiss: () => dismissed++,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('#design'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'gen');
        await tester.pump();
        expect(find.text('#design'), findsNothing);
        expect(find.text('#general'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(selected, ['general']);
        await tester.enterText(find.byType(TextField), 'absent');
        await tester.pump();
        expect(find.text('No results'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(selected, ['general']);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(dismissed, 1);
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();
        await tester.tap(find.text('#design'));
        expect(selected, ['general', 'design']);
        update(() => enabled = false);
        await tester.pump();
        await tester.tap(find.text('#design'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(selected, ['general', 'design']);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('Combobox rejects retired selections $theme', (tester) async {
      final selected = <String>[];
      var options = const {'general': '#general'};
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(theme.$1, dark: theme.$2),
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return RaftComboboxPanel(
                    label: 'Channels',
                    options: options,
                    enabled: enabled,
                    onSelected: selected.add,
                    onDismiss: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      final select = tester
          .widget<RaftInteractive>(
            find.ancestor(
              of: find.text('#general'),
              matching: find.byType(RaftInteractive),
            ),
          )
          .onPressed!;
      update(() => options = const {});
      await tester.pump();
      select();
      expect(selected, isEmpty);
      update(() {
        options = const {'general': '#general'};
        enabled = false;
      });
      await tester.pump();
      select();
      expect(selected, isEmpty);
      update(() => enabled = true);
      await tester.pump();
      select();
      expect(selected, ['general']);
      await tester.pumpWidget(const SizedBox());
      select();
      expect(selected, ['general']);
      expect(tester.takeException(), isNull);
    });
  }

  group('item rows', () {
    final items = [
      const RaftComboboxItem(
        'connection:a',
        'DeepSeek · Team key',
        hint: 'connection:a',
        keywords: 'connection:a',
        group: 'Saved providers',
      ),
      const RaftComboboxItem(
        'connection:old',
        'DeepSeek · Retired key',
        keywords: 'connection:old',
        group: 'Saved providers',
        enabled: false,
      ),
      const RaftComboboxItem(
        'deepseek',
        'DeepSeek',
        hint: 'deepseek',
        keywords: 'deepseek',
        group: 'Direct setup',
      ),
      const RaftComboboxItem(
        'gone',
        'gone',
        description: 'Not in the current list',
      ),
    ];
    Future<List<String>> open(
      WidgetTester tester, {
      List<String> custom = const [],
      String? currentId,
    }) async {
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: RaftComboboxPanel.items(
                label: 'Provider',
                items: items,
                currentId: currentId,
                onSelected: selected.add,
                onDismiss: () {},
                customLabel: (typed) => 'Use “$typed”',
                onCustom: custom.add,
              ),
            ),
          ),
        ),
      );
      return selected;
    }

    testWidgets('groups, descriptions and disabled rows', (tester) async {
      final selected = await open(tester);
      expect(find.text('Saved providers'), findsOneWidget);
      expect(find.text('Direct setup'), findsOneWidget);
      expect(find.text('Not in the current list'), findsOneWidget);
      // A named option shows its stored id beneath; an id-named one does not.
      expect(find.text('deepseek'), findsOneWidget);
      expect(find.text('gone'), findsOneWidget);
      await tester.tap(find.text('DeepSeek · Retired key'));
      expect(selected, isEmpty, reason: 'a disabled row cannot be chosen');
      await tester.tap(find.text('DeepSeek · Team key'));
      expect(selected, ['connection:a']);
    });

    testWidgets('search matches each word in name, id, group or description', (
      tester,
    ) async {
      await open(tester);
      Future<void> search(String text) async {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
      }

      await search('team deep');
      expect(find.text('DeepSeek · Team key'), findsOneWidget);
      expect(find.text('DeepSeek · Retired key'), findsNothing);
      await search('direct');
      expect(find.text('DeepSeek'), findsOneWidget);
      expect(find.text('DeepSeek · Team key'), findsNothing);
      await search('connection:old');
      expect(find.text('DeepSeek · Retired key'), findsOneWidget);
      await search('current list');
      expect(find.text('gone'), findsOneWidget);
    });

    testWidgets('typed text that matches no row is offered as a custom value', (
      tester,
    ) async {
      final custom = <String>[];
      final selected = await open(tester, custom: custom, currentId: 'gone');
      await tester.enterText(find.byType(TextField), 'my-model');
      await tester.pump();
      expect(find.text('No results'), findsNothing);
      await tester.tap(find.text('Use “my-model”'));
      expect(custom, ['my-model']);
      expect(selected, isEmpty);
      // An existing id or the current value is not offered again.
      await tester.enterText(find.byType(TextField), 'deepseek');
      await tester.pump();
      expect(find.text('Use “deepseek”'), findsNothing);
      await tester.enterText(find.byType(TextField), 'gone');
      await tester.pump();
      expect(find.text('Use “gone”'), findsNothing);
    });

    testWidgets('arrow keys skip disabled rows', (tester) async {
      final selected = await open(tester);
      await tester.tap(find.byType(TextField));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(selected, ['deepseek']);
    });
  });
}
